extends SceneTree

const ContentRegistryScript := preload("res://src/content/content_registry.gd")

const HOLD_IDS := ["H01","H02","H03","H04","H05","H06","H07","H08","H09","H10","H11","H12"]
const HOLD_FAMILY_IDS := ["HF1","HF2","HF3","HF4","HF5"]
const HAZARD_IDS := ["RH1","RH2","RH3","RH4","RH5","RH6","RH7"]
const EFFECT_GRAMMAR := [
	"heat_input","contamination_source","stress_field","wake_request","power_capacity_change",
	"decay_modifier","vent_modifier","heat_removal_input","existing_input_sequence"
]

var failures: int = 0

func _init() -> void:
	_test_launch_topology_and_route_metadata()
	if failures == 0:
		print("launch_topology_route_content_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_topology_route_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_launch_topology_and_route_metadata() -> void:
	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded: Dictionary = registry.load_families({
		&"hazards": "res://content/hazards",
		&"holds": "res://content/holds",
		&"routes": "res://content/routes",
	})
	_expect_true(bool(loaded.get("ok", false)), "hold/hazard/route content loads through ContentRegistry")
	if not bool(loaded.get("ok", false)):
		push_error("registry load error: %s" % String(loaded.get("error", "")))
		return

	var hold_payload: Dictionary = _payload_by_id(registry.ordered_documents(&"holds"), &"LAUNCH_HOLDS")
	var hazard_payload: Dictionary = _payload_by_id(registry.ordered_documents(&"hazards"), &"LAUNCH_HAZARD_FAMILIES")
	var route_payload: Dictionary = _payload_by_id(registry.ordered_documents(&"routes"), &"LAUNCH_ROUTE_POLICY")

	var hold_families: Array = _array(hold_payload.get("families", []))
	var hold_definitions: Array = _array(hold_payload.get("definitions", []))
	var hazard_definitions: Array = _array(hazard_payload.get("definitions", []))

	_expect_equal(_sorted_ids(hold_families), PackedStringArray(HOLD_FAMILY_IDS), "exact HF1-HF5 family set")
	_expect_equal(_sorted_ids(hold_definitions), PackedStringArray(HOLD_IDS), "exact H01-H12 layout set")
	_expect_equal(_sorted_ids(hazard_definitions), PackedStringArray(HAZARD_IDS), "exact RH1-RH7 hazard-family set")

	var family_ids: Dictionary = _id_set(hold_families)
	var hold_ids: Dictionary = _id_set(hold_definitions)
	for raw_hold: Variant in hold_definitions:
		var hold: Dictionary = _dict(raw_hold)
		var hold_id: String = String(hold.get("id", ""))
		var family_id: String = String(hold.get("family_id", ""))
		_expect_true(family_ids.has(family_id), "%s family reference resolves" % hold_id)
		_expect_equal(String(hold.get("fixture_policy", "")), "family", "%s inherits frozen fixture policy" % hold_id)

	var expected_family_layout_counts := {"HF1":3, "HF2":3, "HF3":2, "HF4":2, "HF5":2}
	for raw_family: Variant in hold_families:
		var family: Dictionary = _dict(raw_family)
		var family_id: String = String(family.get("id", ""))
		var layout_ids: Array = _array(family.get("layouts", []))
		_expect_equal(layout_ids.size(), int(expected_family_layout_counts.get(family_id, -1)), "%s canonical layout count" % family_id)
		for raw_layout_id: Variant in layout_ids:
			_expect_true(hold_ids.has(String(raw_layout_id)), "%s layout reference %s resolves" % [family_id, String(raw_layout_id)])

	var allowed_effects: Dictionary = {}
	for effect: Variant in EFFECT_GRAMMAR:
		allowed_effects[String(effect)] = true
	for raw_hazard: Variant in hazard_definitions:
		var hazard: Dictionary = _dict(raw_hazard)
		var hazard_id: String = String(hazard.get("id", ""))
		var grammar: Array = _array(hazard.get("effect_grammar", []))
		_expect_true(not grammar.is_empty(), "%s declares existing effect grammar" % hazard_id)
		for raw_effect: Variant in grammar:
			_expect_true(allowed_effects.has(String(raw_effect)), "%s effect %s stays inside frozen grammar" % [hazard_id, String(raw_effect)])
	var rh7: Dictionary = _dict(_by_id(hazard_definitions).get("RH7", {}))
	_expect_true(not bool(rh7.get("new_effect_type", true)), "RH7 is explicitly a sequence of existing inputs")

	var hazard_ids: Dictionary = _id_set(hazard_definitions)
	var route_hazard_ids: Array = _array(route_payload.get("hazard_family_ids", []))
	_expect_equal(_sorted_strings(route_hazard_ids), PackedStringArray(HAZARD_IDS), "route policy references exact RH1-RH7 set")
	for raw_id: Variant in route_hazard_ids:
		_expect_true(hazard_ids.has(String(raw_id)), "route hazard reference %s resolves" % String(raw_id))

	_expect_equal(int(route_payload.get("authored_profile_target", 0)), 18, "launch authored route profile target remains 18")
	_expect_equal(int(route_payload.get("normal_route_max_ticks", 0)), 24, "normal route ceiling remains 24 ticks")
	_expect_true(bool(route_payload.get("first_exposure_requires_exact_timing_and_intensity", false)), "first exposure keeps exact timing/intensity")
	_expect_equal(int(route_payload.get("bounded_uncertainty_max_hidden_dimensions", 0)), 1, "bounded uncertainty hides at most one dimension")

	var ceilings: Array = _array(route_payload.get("tier_hazard_family_ceilings", []))
	var by_tier: Dictionary = {}
	for raw_ceiling: Variant in ceilings:
		var ceiling: Dictionary = _dict(raw_ceiling)
		by_tier[String(ceiling.get("tier", ""))] = ceiling
	_expect_equal(int(_dict(by_tier.get("0-1", {})).get("max_families", -1)), 1, "Tier 0-1 max one hazard family")
	_expect_equal(int(_dict(by_tier.get("2", {})).get("max_families", -1)), 1, "Tier 2 max one hazard family")
	_expect_true(bool(_dict(by_tier.get("2", {})).get("may_use_two_non_overlapping_events", false)), "Tier 2 allows two non-overlapping events")
	_expect_equal(int(_dict(by_tier.get("3", {})).get("max_families", -1)), 2, "Tier 3 max two hazard families")
	_expect_equal(int(_dict(by_tier.get("4-5", {})).get("max_families", -1)), 3, "Tier 4-5 max three hazard families")
	_expect_equal(int(_dict(by_tier.get("4-5", {})).get("max_simultaneous", -1)), 2, "Tier 4-5 max two simultaneous families")
	_expect_equal(int(_dict(by_tier.get("6", {})).get("max_families", -1)), 4, "Tier 6 max four hazard families")
	_expect_equal(int(_dict(by_tier.get("6", {})).get("max_simultaneous", -1)), 2, "Tier 6 normal max two simultaneous families")

	var generation: Dictionary = _dict(hold_payload.get("generation", {}))
	_expect_true(bool(generation.get("authored_layouts_only", false)), "launch topology remains authored-layout-only")
	_expect_true(not bool(generation.get("arbitrary_procedural_topology", true)), "arbitrary procedural launch topology remains forbidden")

func _payload_by_id(documents: Array[ContentDocument], id: StringName) -> Dictionary:
	for document: ContentDocument in documents:
		if document.id == id:
			return document.payload.duplicate(true)
	return {}

func _by_id(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_definition: Variant in definitions:
		var definition: Dictionary = _dict(raw_definition)
		result[String(definition.get("id", ""))] = definition
	return result

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

func _sorted_strings(values: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for value: Variant in values:
		result.append(String(value))
	result.sort()
	return result

func _array(value: Variant) -> Array:
	return value if value is Array else []

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
