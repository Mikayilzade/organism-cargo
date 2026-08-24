extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_chapter5_authored_content()
	if failures == 0:
		print("chapter5_authored_content_test_runner: PASS")
		quit(0)
	else:
		push_error("chapter5_authored_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_chapter5_authored_content() -> void:
	var doc: Dictionary = _load_json("res://content/contracts/campaign_chapter5_batch_01.json")
	var definitions: Array = _array(_dict(doc.get("payload", {})).get("definitions", []))
	var expected_prerequisites: Dictionary = {
		"C33": ["C32"],
		"C34": ["C33"],
		"C35": ["C34"],
		"C36": ["C33"],
		"C37": ["C36"],
		"C38": ["C35", "C37"],
		"C39": ["C38"],
		"C40": ["C39"],
	}
	var hold_ids: Dictionary = {}
	var route_defs: Dictionary = {}
	var species_ids: Dictionary = {}
	var support_defs: Dictionary = {}

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
		var support: Dictionary = _dict(raw)
		support_defs[String(support.get("id", ""))] = support

	var monitor: Dictionary = _dict(support_defs.get("S06", {}))
	var monitor_semantics: Dictionary = _dict(monitor.get("semantics", {}))
	_expect(bool(monitor.get("information_only", false)), "S06 remains information-only")
	_expect(not bool(monitor_semantics.get("direct_mitigation", true)), "S06 has no direct mitigation")
	_expect(not bool(monitor_semantics.get("required_for_discovery_bronze", true)), "S06 is never required for discovery Bronze")
	_expect(not bool(monitor_semantics.get("solver_or_recommendation_engine", true)), "S06 is not a solver/recommendation engine")

	var seen: Dictionary = {}
	var discovery_cases: int = 0
	var monitor_cases: int = 0
	var no_monitor_documented_cases: int = 0
	var spacing_inferior: int = 0
	var two_change_cases: int = 0
	var cluster_evidence_cases: int = 0
	var filter_inferior_cases: int = 0
	var baffle_inferior_cases: int = 0
	var capstone_seen: bool = false

	for raw: Variant in definitions:
		var d: Dictionary = _dict(raw)
		var cid: String = String(d.get("id", ""))
		var number: int = int(cid.trim_prefix("C"))
		_expect(number >= 33 and number <= 40, "%s belongs to Chapter 5" % cid)
		_expect(not seen.has(cid), "%s appears once" % cid)
		seen[cid] = true
		_expect(String(d.get("tier", "")) == "5", "%s authored contract tier is 5" % cid)
		_expect(bool(d.get("requires_post_launch_change", false)), "%s preserves dynamic-transit identity" % cid)
		_expect(int(d.get("temporally_separated_changes", 0)) >= 2, "%s has at least two separated transit changes" % cid)
		if int(d.get("temporally_separated_changes", 0)) >= 2:
			two_change_cases += 1
		if bool(d.get("maximum_spacing_inferior", false)):
			spacing_inferior += 1

		var actual_prerequisites: Array = _normalized_strings(d.get("prerequisites", []))
		var expected_value: Variant = expected_prerequisites.get(cid, [])
		var expected: Array = _normalized_strings(expected_value)
		_expect(actual_prerequisites == expected, "%s preserves exact Bronze prerequisite graph" % cid)

		var hold_id: String = String(d.get("hold_id", ""))
		var route_id: String = String(d.get("route_id", ""))
		_expect(hold_ids.has(hold_id), "%s hold resolves" % cid)
		_expect(route_defs.has(route_id), "%s route resolves" % cid)
		var route: Dictionary = _dict(route_defs.get(route_id, {}))
		_expect(String(route.get("tier", "")) in ["3", "4-5"], "%s route stays within Tier-5 complexity ceiling" % cid)
		_expect(int(route.get("duration_ticks", 0)) <= 24, "%s route stays within 24-tick launch ceiling" % cid)

		for species_id: Variant in _array(d.get("species_ids", [])):
			_expect(species_ids.has(String(species_id)), "%s species %s resolves" % [cid, String(species_id)])
		for support_id: Variant in _array(d.get("support_ids", [])):
			_expect(support_defs.has(String(support_id)), "%s support %s resolves" % [cid, String(support_id)])

		var support_ids: Array = _array(d.get("support_ids", []))
		if support_ids.has("S06"):
			monitor_cases += 1
			_expect(bool(d.get("monitor_allowed", false)), "%s explicitly permits Monitor evidence" % cid)
			_expect(not bool(d.get("monitor_required_for_bronze", true)), "%s does not require Monitor for Bronze" % cid)
			_expect(bool(d.get("bronze_without_monitor_certified", false)), "%s certifies Bronze without Monitor" % cid)
			_expect(not bool(d.get("monitor_direct_mitigation", true)), "%s gives Monitor no mitigation" % cid)
		elif String(d.get("documentation_state", "")) == "documented":
			no_monitor_documented_cases += 1

		var hidden_dimensions: Array = _array(d.get("hidden_information_dimensions", []))
		if bool(d.get("discovery", false)):
			discovery_cases += 1
			_expect(String(d.get("documentation_state", "")) == "bounded_discovery", "%s marks bounded discovery" % cid)
			_expect(hidden_dimensions.size() == 1, "%s hides exactly one independent information dimension" % cid)
			_expect(bool(d.get("bronze_without_monitor_certified", false)), "%s discovery remains solvable without Monitor" % cid)
		else:
			_expect(hidden_dimensions.size() <= 1, "%s never hides multiple independent dimensions" % cid)

		if bool(d.get("helper_protector_cluster_evidence", false)):
			cluster_evidence_cases += 1
			var species: Array = _array(d.get("species_ids", []))
			_expect(species.has("O05") or species.has("O06") or species.has("O12") or species.has("O16") or species.has("O19") or species.has("O20"), "%s cluster evidence binds a frozen comparison-cluster species" % cid)

		if bool(d.get("filter_inferior", false)):
			filter_inferior_cases += 1
			_expect(support_ids.has("S02"), "%s Filter inferiority is tested with S02 legal" % cid)
			_expect(String(d.get("filter_inferior_reason", "")).length() >= 40, "%s records Filter inferiority reason" % cid)
		if bool(d.get("baffle_inferior", false)):
			baffle_inferior_cases += 1
			_expect(support_ids.has("S03"), "%s Baffle inferiority is tested with S03 legal" % cid)
			_expect(String(d.get("baffle_inferior_reason", "")).length() >= 40, "%s records Baffle inferiority reason" % cid)

		if cid == "C33":
			_expect(support_ids.has("S06"), "C33 introduces Monitor Beacon S06")
		if cid == "C34":
			_expect(_array(d.get("species_ids", [])).has("O15"), "C34 discovers Lantern Tick O15")
			_expect(String(d.get("discovery_species_id", "")) == "O15", "C34 binds discovery to O15")
		if cid == "C35":
			_expect(_array(d.get("species_ids", [])).has("O15"), "C35 documents Lantern Tick O15")
			_expect(String(d.get("documentation_state", "")) == "documented", "C35 is documented normal use")
		if cid == "C36":
			_expect(_array(d.get("species_ids", [])).has("O21"), "C36 discovers Pale Drifter O21")
			_expect(String(d.get("discovery_species_id", "")) == "O21", "C36 binds discovery to O21")
			var wake_seen: bool = false
			for event_value: Variant in _array(route.get("events", [])):
				if String(_dict(event_value).get("effect", "")) == "wake_request":
					wake_seen = true
			_expect(wake_seen, "C36 bounded wake discovery binds a route with explicit wake request")
		if cid == "C37":
			_expect(_array(d.get("species_ids", [])).has("O21"), "C37 documents Pale Drifter O21")
			_expect(String(d.get("documentation_state", "")) == "documented", "C37 is documented normal use")
		if cid == "C38":
			_expect(String(d.get("advanced_lifecycle_species_id", "")) == "O18", "C38 binds advanced lifecycle to Spindle Bloom O18")
			_expect(_array(d.get("species_ids", [])).has("O18"), "C38 contains Spindle Bloom O18")
		if cid == "C39":
			_expect(String(d.get("dependency_species_id", "")) == "O19", "C39 binds dependency to Amber Leech O19")
			_expect(bool(d.get("feeding_conservation_required", false)), "C39 preserves feeding conservation")
		if cid == "C40":
			capstone_seen = true
			var uncertainty: Dictionary = _dict(d.get("bounded_route_uncertainty", {}))
			_expect(_array(uncertainty.get("hidden_dimensions", [])).size() == 1, "C40 hides exactly one route-information dimension")
			_expect(_array(uncertainty.get("hidden_dimensions", [])).has("event_tick"), "C40 hidden route dimension is timing only")
			_expect(_array(uncertainty.get("disclosed_dimensions", [])).size() >= 3, "C40 discloses the other route dimensions")
			_expect(_array(uncertainty.get("monitor_reveals", [])).has("event_tick"), "C40 Monitor reveals only the bounded timing evidence")
			_expect(bool(uncertainty.get("bronze_without_monitor_certified", false)), "C40 capstone has a certified no-Monitor Bronze family")
			_expect(String(d.get("monitor_tradeoff_reason", "")).length() >= 40, "C40 records Monitor opportunity cost")
			_expect(route_id == "R18", "C40 capstone uses existing Tier-5 R18 profile")

	_expect(seen.size() == 8, "Chapter 5 payload covers C33-C40 exactly")
	_expect(discovery_cases == 2, "Chapter 5 has exactly the Lantern Tick and Pale Drifter bounded-discovery cases")
	_expect(monitor_cases >= 3, "Monitor receives preferred evidence cases C33/C36/C40")
	_expect(no_monitor_documented_cases >= 3, "fully documented Chapter-5 cases prove Monitor is unnecessary")
	_expect(spacing_inferior >= 2, "Chapter 5 has at least two maximum-spacing-inferior contracts")
	_expect(two_change_cases >= 6, "Chapter 5 strongly contributes two-change dynamic-transit cases")
	_expect(cluster_evidence_cases >= 3, "Chapter 5 records helper/protector comparison-cluster evidence")
	_expect(filter_inferior_cases >= 1, "Chapter 5 includes canonical C39 Filter-inferior proof")
	_expect(baffle_inferior_cases >= 1, "Chapter 5 includes canonical C39 Baffle-inferior proof")
	_expect(capstone_seen, "C40 bounded-route-information capstone exists")

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
