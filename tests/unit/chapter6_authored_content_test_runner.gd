extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_chapter6_authored_content()
	if failures == 0:
		print("chapter6_authored_content_test_runner: PASS")
		quit(0)
	else:
		push_error("chapter6_authored_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_chapter6_authored_content() -> void:
	var doc: Dictionary = _load_json("res://content/contracts/campaign_chapter6_batch_01.json")
	var definitions: Array = _array(_dict(doc.get("payload", {})).get("definitions", []))
	var expected_prerequisites: Dictionary = {
		"C41": ["C40"],
		"C42": ["C40"],
		"C43": ["C41", "C42"],
		"C44": ["C43"],
		"C45": ["C43"],
		"C46": ["C44", "C45"],
		"C47": ["C46"],
		"C48": ["C47"],
	}
	var hold_ids: Dictionary = {}
	var route_defs: Dictionary = {}
	var species_ids: Dictionary = {}
	var support_ids: Dictionary = {}

	for path: String in [
		"res://content/holds/launch_hold_geometry_batch_01.json",
		"res://content/holds/launch_hold_geometry_batch_02.json",
		"res://content/holds/launch_hold_geometry_batch_03.json"
	]:
		for raw: Variant in _array(_dict(_load_json(path).get("payload", {})).get("definitions", [])):
			hold_ids[String(_dict(raw).get("id", ""))] = true

	for path: String in [
		"res://content/routes/launch_route_profiles_batch_01.json",
		"res://content/routes/launch_route_profiles_batch_02.json",
		"res://content/routes/launch_route_profiles_batch_03.json"
	]:
		for raw: Variant in _array(_dict(_load_json(path).get("payload", {})).get("definitions", [])):
			var route: Dictionary = _dict(raw)
			route_defs[String(route.get("id", ""))] = route

	for raw: Variant in _array(_dict(_load_json("res://content/species/launch_roster.json").get("payload", {})).get("definitions", [])):
		species_ids[String(_dict(raw).get("id", ""))] = true

	for raw: Variant in _array(_dict(_load_json("res://content/supports/launch_supports.json").get("payload", {})).get("definitions", [])):
		support_ids[String(_dict(raw).get("id", ""))] = true

	var seen: Dictionary = {}
	var two_change_cases: int = 0
	var spacing_inferior_cases: int = 0
	var growth_edge_inferior_cases: int = 0
	var helper_cluster_cases: int = 0
	var familiar_helper_inferior_cases: int = 0
	var inferior_powered_support_cases: int = 0
	var thermal_gradient_cases: int = 0
	var maintenance_cases: int = 0
	var final_seen: bool = false

	for raw: Variant in definitions:
		var d: Dictionary = _dict(raw)
		var cid: String = String(d.get("id", ""))
		var number: int = int(cid.trim_prefix("C"))
		_expect(number >= 41 and number <= 48, "%s belongs to Chapter 6" % cid)
		_expect(not seen.has(cid), "%s appears once" % cid)
		seen[cid] = true
		_expect(String(d.get("tier", "")) == "6", "%s authored contract tier is 6" % cid)
		_expect(bool(d.get("requires_post_launch_change", false)), "%s preserves dynamic-transit identity" % cid)
		_expect(int(d.get("temporally_separated_changes", 0)) >= 2, "%s has at least two separated transit changes" % cid)
		if int(d.get("temporally_separated_changes", 0)) >= 2:
			two_change_cases += 1
		if bool(d.get("maximum_spacing_inferior", false)):
			spacing_inferior_cases += 1

		var actual_prerequisites: Array = _normalized_strings(d.get("prerequisites", []))
		var expected: Array = _normalized_strings(expected_prerequisites.get(cid, []))
		_expect(actual_prerequisites == expected, "%s preserves exact Bronze prerequisite graph" % cid)

		var hold_id: String = String(d.get("hold_id", ""))
		var route_id: String = String(d.get("route_id", ""))
		_expect(hold_id in ["H11", "H12"], "%s uses frozen Constricted Vault mastery topology" % cid)
		_expect(hold_ids.has(hold_id), "%s hold resolves" % cid)
		_expect(route_id in ["R16", "R17", "R18"], "%s uses existing late-route grammar" % cid)
		_expect(route_defs.has(route_id), "%s route resolves" % cid)
		var route: Dictionary = _dict(route_defs.get(route_id, {}))
		_expect(int(route.get("duration_ticks", 0)) <= 24, "%s route stays within launch tick ceiling" % cid)
		_expect(_array(route.get("hazard_family_ids", [])).size() <= 4, "%s route stays within Tier-6 hazard-family ceiling" % cid)

		for species_id: Variant in _array(d.get("species_ids", [])):
			_expect(species_ids.has(String(species_id)), "%s species %s resolves" % [cid, String(species_id)])
		for support_id: Variant in _array(d.get("support_ids", [])):
			_expect(support_ids.has(String(support_id)), "%s support %s resolves" % [cid, String(support_id)])

		if bool(d.get("growth_reserve_edge_inferior", false)):
			growth_edge_inferior_cases += 1
			var species: Array = _array(d.get("species_ids", []))
			_expect(species.has("O22") or species.has("O18") or species.has("O13") or species.has("O08") or species.has("O03"), "%s growth-reserve anti-template binds a growth species" % cid)
			_expect(String(d.get("growth_reserve_reason", "")).length() >= 60, "%s records explicit growth-reserve anti-template reason" % cid)

		if bool(d.get("helper_protector_cluster_evidence", false)):
			helper_cluster_cases += 1
			var cluster_species: Array = _array(d.get("species_ids", []))
			_expect(cluster_species.has("O05") or cluster_species.has("O06") or cluster_species.has("O12") or cluster_species.has("O16") or cluster_species.has("O19") or cluster_species.has("O20"), "%s helper/protector evidence binds a frozen comparison cluster" % cid)

		if bool(d.get("familiar_helper_inferior", false)):
			familiar_helper_inferior_cases += 1
			var helper_species: Array = _array(d.get("species_ids", []))
			_expect(helper_species.has("O12") or helper_species.has("O16") or helper_species.has("O06"), "%s familiar-helper inferiority binds a helper species" % cid)

		if bool(d.get("cooler_or_filter_inferior", false)):
			inferior_powered_support_cases += 1
			_expect(String(d.get("inferior_support_reason", "")).length() >= 60, "%s records Cooler/Filter inferiority reason" % cid)

		if bool(d.get("thermal_gradient_evidence", false)):
			thermal_gradient_cases += 1
			_expect(route_id == "R18", "%s Thermal Gradient recombination binds R18" % cid)
			_expect(_array(route.get("hazard_family_ids", [])).has("RH6"), "%s route exposes RH6 Thermal Gradient" % cid)
			_expect(_array(d.get("support_ids", [])).has("S01"), "%s provides canonical Cooler proof" % cid)

		if bool(d.get("maintenance_oscillation_evidence", false)):
			maintenance_cases += 1
			_expect(_array(route.get("hazard_family_ids", [])).has("RH7"), "%s route exposes RH7 Maintenance Oscillation" % cid)

		if cid == "C41":
			_expect(String(d.get("advanced_composite_species_id", "")) == "O09", "C41 binds Ash Sponge O09")
		if cid == "C42":
			_expect(String(d.get("mastery_species_id", "")) == "O22", "C42 binds Splitcap O22")
			_expect(bool(d.get("future_footprint_solver_validated", false)), "C42 validates Splitcap future footprint")
			_expect(bool(d.get("post_growth_adjacency_validated", false)), "C42 validates Splitcap post-growth adjacency")
		if cid == "C43":
			_expect(bool(d.get("constricted_vault_mastery", false)), "C43 is Constricted Vault mastery topology")
		if cid == "C46":
			_expect(bool(d.get("anti_template_helper_liability", false)), "C46 encodes anti-template helper-liability test")
			_expect(bool(d.get("universal_helper_solution_forbidden", false)), "C46 rejects universal-helper solution")
		if cid == "C47":
			_expect(bool(d.get("full_system_mastery", false)), "C47 is penultimate full-system mastery")
		if cid == "C48":
			final_seen = true
			_expect(bool(d.get("living_manifest_final", false)), "C48 is final Living Manifest")
			_expect(hold_id == "H12", "C48 uses irregular S-Corridor Vault")
			_expect(int(d.get("organism_count", 0)) >= 7 and int(d.get("organism_count", 0)) <= 9, "C48 has 7-9 organisms")
			_expect(_array(d.get("species_ids", [])).size() == int(d.get("organism_count", 0)), "C48 organism count matches manifest")
			_expect(int(d.get("learned_role_family_count", 0)) >= 5, "C48 spans at least five learned role families")
			_expect(not _array(d.get("lifecycle_species_ids", [])).is_empty(), "C48 includes lifecycle species")
			_expect(not _array(d.get("beneficial_dangerous_composite_ids", [])).is_empty(), "C48 includes beneficial-dangerous composite")
			_expect(_array(d.get("known_hazard_family_sequence", [])).size() == 3, "C48 has three known hazard families in readable sequence")
			_expect(_array(route.get("hazard_family_ids", [])).size() >= 3, "C48 bound route supplies at least three known hazard families")
			_expect(bool(d.get("power_fixture_pressure", false)), "C48 includes power/fixture pressure")
			_expect(_array(d.get("certified_bronze_strategy_families", [])).size() >= 2, "C48 has at least two certified Bronze strategy families")
			_expect(bool(d.get("gold_requires_efficient_support_and_welfare_stability", false)), "C48 Gold rewards support efficiency and welfare stability")
			_expect(bool(d.get("gold_intentional_harm_forbidden", false)), "C48 Gold never rewards intentional harm")
			_expect(not bool(d.get("introduces_new_rule", true)), "C48 introduces no new rule")

	_expect(seen.size() == 8, "Chapter 6 payload covers C41-C48 exactly")
	_expect(two_change_cases == 8, "all Chapter-6 contracts require multiple temporally separated changes")
	_expect(spacing_inferior_cases >= 2, "Chapter 6 has at least two maximum-spacing-inferior cases")
	_expect(growth_edge_inferior_cases >= 2, "Chapter 6 has at least two permanent growth-corner/edge anti-template cases")
	_expect(helper_cluster_cases >= 5, "Chapter 6 repeatedly exercises helper/protector comparison clusters")
	_expect(familiar_helper_inferior_cases >= 3, "Tier-6 mastery makes familiar helper choices inferior in multiple cases")
	_expect(inferior_powered_support_cases >= 1, "Chapter 6 makes Cooler or Filter actively inferior")
	_expect(thermal_gradient_cases >= 1, "Chapter 6 includes Thermal Gradient recombination")
	_expect(maintenance_cases >= 1, "Chapter 6 includes Maintenance Oscillation recombination")
	_expect(final_seen, "C48 Living Manifest exists")

func _normalized_strings(value: Variant) -> Array:
	var values: Array = []
	if not value is Array:
		return values
	for raw: Variant in value:
		values.append(String(raw))
	values.sort()
	return values

func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "parse %s" % path)
	return _dict(parsed)

func _array(value: Variant) -> Array:
	return value if value is Array else []

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
