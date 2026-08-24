extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_chapter4_authored_content()
	if failures == 0:
		print("chapter4_authored_content_test_runner: PASS")
		quit(0)
	else:
		push_error("chapter4_authored_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_chapter4_authored_content() -> void:
	var doc: Dictionary = _load_json("res://content/contracts/campaign_chapter4_batch_01.json")
	var definitions: Array = _array(_dict(doc.get("payload", {})).get("definitions", []))
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

	var seen: Dictionary = {}
	var spacing_inferior: int = 0
	var two_change_cases: int = 0
	var growth_edge_inferior: int = 0
	var directed_overlay_cases: int = 0
	var brownout_priority_cases: int = 0
	var inferior_powered_support_cases: int = 0
	var downside_cases: int = 0
	var service_bay_cases: int = 0
	var capstone_seen: bool = false

	for raw: Variant in definitions:
		var d: Dictionary = _dict(raw)
		var cid: String = String(d.get("id", ""))
		var number: int = int(cid.trim_prefix("C"))
		_expect(number >= 25 and number <= 32, "%s belongs to Chapter 4" % cid)
		_expect(not seen.has(cid), "%s appears once" % cid)
		seen[cid] = true
		_expect(String(d.get("tier", "")) == "4", "%s authored contract tier is 4" % cid)
		_expect(bool(d.get("requires_post_launch_change", false)), "%s preserves dynamic-transit identity" % cid)
		_expect(int(d.get("temporally_separated_changes", 0)) >= 2, "%s has at least two separated transit changes" % cid)
		if int(d.get("temporally_separated_changes", 0)) >= 2:
			two_change_cases += 1

		var hold_id: String = String(d.get("hold_id", ""))
		var route_id: String = String(d.get("route_id", ""))
		_expect(hold_ids.has(hold_id), "%s hold resolves" % cid)
		_expect(route_defs.has(route_id), "%s route resolves" % cid)
		var route: Dictionary = _dict(route_defs.get(route_id, {}))
		_expect(String(route.get("tier", "")) in ["3", "4-5"], "%s route stays within Tier-4 complexity ceiling" % cid)

		for sid: Variant in _array(d.get("species_ids", [])):
			_expect(species_ids.has(String(sid)), "%s species %s resolves" % [cid, String(sid)])
		for support_id: Variant in _array(d.get("support_ids", [])):
			_expect(support_defs.has(String(support_id)), "%s support %s resolves" % [cid, String(support_id)])

		if bool(d.get("maximum_spacing_inferior", false)):
			spacing_inferior += 1
		if bool(d.get("growth_reserve_edge_inferior", false)):
			growth_edge_inferior += 1
			_expect(_array(d.get("species_ids", [])).has("O08") or _array(d.get("species_ids", [])).has("O13") or _array(d.get("species_ids", [])).has("O18") or _array(d.get("species_ids", [])).has("O22"), "%s growth-reserve anti-template binds an authored growth species" % cid)
			_expect(String(d.get("growth_reserve_reason", "")).length() >= 40, "%s growth-reserve anti-template has explicit reason" % cid)

		if bool(d.get("directed_overlay_evidence", false)):
			directed_overlay_cases += 1
			_expect(_array(d.get("species_ids", [])).has("O11"), "%s directed overlay binds Rattle Reed O11" % cid)
			_expect(_array(d.get("support_ids", [])).has("S03"), "%s directed overlay provides Baffle interaction evidence" % cid)

		if hold_id in ["H09", "H10"]:
			service_bay_cases += 1
		if cid == "C28":
			_expect(hold_id == "H09", "C28 introduces Service Bay H09")
		if number >= 29:
			_expect(hold_id in ["H09", "H10"], "%s keeps Chapter-4 fixture pressure in Service Bay family" % cid)

		if bool(d.get("brownout_support_priority", false)):
			brownout_priority_cases += 1
			var has_rh4: bool = false
			for raw_event: Variant in _array(route.get("events", [])):
				var event: Dictionary = _dict(raw_event)
				if String(event.get("family_id", "")) == "RH4" and String(event.get("effect", "")) == "power_capacity_change":
					has_rh4 = true
			_expect(has_rh4, "%s Brownout priority evidence binds an RH4 power-capacity event" % cid)
			var powered_choices: int = 0
			for support_id: Variant in _array(d.get("support_ids", [])):
				if bool(_dict(support_defs.get(String(support_id), {})).get("requires_power", false)):
					powered_choices += 1
			_expect(powered_choices >= 1, "%s Brownout evidence includes a powered support decision" % cid)

		if bool(d.get("cooler_or_filter_inferior", false)):
			inferior_powered_support_cases += 1
			_expect(String(d.get("inferior_support_reason", "")).length() >= 40, "%s records why Cooler/Filter is actively inferior" % cid)

		if bool(d.get("helper_protector_downside", false)):
			downside_cases += 1
			var species: Array = _array(d.get("species_ids", []))
			_expect(species.has("O12") or species.has("O17") or species.has("O20") or species.has("O05"), "%s downside evidence binds a helper/protector species" % cid)

		if cid == "C25": _expect(_array(d.get("species_ids", [])).has("O07"), "C25 introduces Pulse Mite O07")
		if cid == "C26": _expect(_array(d.get("species_ids", [])).has("O12"), "C26 introduces Velvet Nurse O12")
		if cid == "C27": _expect(_array(d.get("species_ids", [])).has("O11"), "C27 introduces Rattle Reed O11")
		if cid == "C30": _expect(_array(d.get("species_ids", [])).has("O17"), "C30 introduces Coal Urchin O17")
		if cid == "C31": _expect(_array(d.get("species_ids", [])).has("O20"), "C31 introduces Whistle Crab O20")
		if cid == "C32":
			capstone_seen = true
			_expect(int(d.get("interruptible_cascade_steps", 0)) == 4, "C32 encodes the frozen interruptible four-step cascade capstone")
			_expect(bool(d.get("brownout_support_priority", false)), "C32 capstone includes Brownout/support priority")
			_expect(bool(d.get("directed_overlay_evidence", false)), "C32 capstone recombines directed overlay")
			_expect(bool(d.get("helper_protector_downside", false)), "C32 capstone recombines helper/protector downside")

	_expect(seen.size() == 8, "Chapter 4 payload covers C25-C32 exactly")
	_expect(spacing_inferior >= 2, "Chapter 4 has at least two maximum-spacing-inferior cases")
	_expect(two_change_cases >= 6, "Chapter 4 strongly contributes two-change dynamic-transit cases")
	_expect(growth_edge_inferior >= 1, "Chapter 4 breaks the permanent growth corner/edge reserve template")
	_expect(directed_overlay_cases >= 2, "Chapter 4 includes directed-overlay introduction and capstone recombination")
	_expect(service_bay_cases >= 5, "Chapter 4 establishes sustained Service Bay fixture competition")
	_expect(brownout_priority_cases >= 2, "Chapter 4 includes Brownout support-priority teaching and capstone reuse")
	_expect(inferior_powered_support_cases >= 1, "Chapter 4 makes Cooler or Filter actively inferior")
	_expect(downside_cases >= 3, "Chapter 4 repeatedly proves helper/protector downside rather than universal protection")
	_expect(capstone_seen, "C32 capstone exists")

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
