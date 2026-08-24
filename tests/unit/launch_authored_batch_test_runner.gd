extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_hold_geometry()
	_test_route_profiles()
	_test_campaign_contracts()
	if failures == 0:
		print("launch_authored_batch_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_authored_batch_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_hold_geometry() -> void:
	var docs: Array = [_load_json("res://content/holds/launch_hold_geometry_batch_01.json"), _load_json("res://content/holds/launch_hold_geometry_batch_02.json"), _load_json("res://content/holds/launch_hold_geometry_batch_03.json")]
	var limits: Dictionary = {
		"H01":[5,6,5,5,1,2],"H02":[5,6,5,5,1,2],"H03":[5,6,5,5,1,2],
		"H04":[5,6,6,6,2,2],"H05":[5,6,6,6,2,2],"H06":[5,6,6,6,2,2],
		"H07":[5,9,5,7,2,3],"H08":[5,9,5,7,2,3],"H09":[5,9,5,7,2,6],"H10":[5,9,5,7,2,6],
		"H11":[7,9,6,7,0,6],"H12":[7,9,6,7,0,6]
	}
	var seen: Dictionary = {}
	for raw_doc: Variant in docs:
		for raw_definition: Variant in _array(_dict(_dict(raw_doc).get("payload", {})).get("definitions", [])):
			var definition: Dictionary = _dict(raw_definition)
			var hold_id: String = String(definition.get("id", ""))
			_expect(limits.has(hold_id), "%s is expected authored hold" % hold_id)
			_expect(not seen.has(hold_id), "%s appears once" % hold_id)
			seen[hold_id] = true
			if not limits.has(hold_id): continue
			var limit: Array = _array(limits[hold_id])
			var width: int = int(definition.get("width", 0)); var height: int = int(definition.get("height", 0))
			_expect(width >= int(limit[0]) and width <= int(limit[1]) and height >= int(limit[2]) and height <= int(limit[3]), "%s stays inside frozen family bounds" % hold_id)
			var fixtures: Array = _array(definition.get("utility_fixtures", []))
			_expect(fixtures.size() >= int(limit[4]) and fixtures.size() <= int(limit[5]), "%s fixture count stays inside frozen family bounds" % hold_id)
			var blocked: Dictionary = {}; var fixture_cells: Dictionary = {}
			for raw_cell: Variant in _array(definition.get("blocked_cells", [])):
				var cell: Array = _array(raw_cell); _expect(_in_bounds(cell, width, height), "%s blocked cell in bounds" % hold_id); blocked[_cell_key(cell)] = true
			for raw_fixture: Variant in fixtures:
				var cell: Array = _array(_dict(raw_fixture).get("cell", [])); var key: String = _cell_key(cell)
				_expect(_in_bounds(cell, width, height), "%s fixture cell in bounds" % hold_id); _expect(not blocked.has(key), "%s fixture not blocked" % hold_id); _expect(not fixture_cells.has(key), "%s fixture cells unique" % hold_id); fixture_cells[key] = true
			if hold_id in ["H11","H12"]:
				var fraction: float = float(blocked.size()) / float(width * height)
				_expect(fraction >= 0.20 and fraction <= 0.35, "%s blocked fraction stays inside HF5 freeze" % hold_id)
	_expect(seen.size() == 12, "authored geometry covers H01-H12")

func _test_route_profiles() -> void:
	var docs: Array = [_load_json("res://content/routes/launch_route_profiles_batch_01.json"), _load_json("res://content/routes/launch_route_profiles_batch_02.json"), _load_json("res://content/routes/launch_route_profiles_batch_03.json")]
	var allowed_effects: Dictionary = {"RH1":["heat_input"],"RH2":["contamination_source"],"RH3":["stress_field","wake_request"],"RH4":["power_capacity_change"],"RH5":["decay_modifier","vent_modifier","heat_removal_input"],"RH6":["heat_input"],"RH7":["existing_input_sequence"]}
	var seen: Dictionary = {}
	for raw_doc: Variant in docs:
		for raw_definition: Variant in _array(_dict(_dict(raw_doc).get("payload", {})).get("definitions", [])):
			var d: Dictionary = _dict(raw_definition); var route_id: String = String(d.get("id", "")); var tier: String = String(d.get("tier", "")); var duration: int = int(d.get("duration_ticks", 0)); var families: Array = _array(d.get("hazard_family_ids", [])); var events: Array = _array(d.get("events", []))
			_expect(not seen.has(route_id), "%s appears once" % route_id); seen[route_id] = true; _expect(duration > 0 and duration <= 24, "%s duration <=24" % route_id)
			var max_families: int = 2
			if tier == "0-1" or tier == "2": max_families = 1
			elif tier == "4-5": max_families = 3
			elif tier == "6": max_families = 4
			_expect(families.size() <= max_families, "%s tier family ceiling" % route_id)
			var declared: Dictionary = {}
			for raw_family: Variant in families:
				var family_id: String = String(raw_family); _expect(allowed_effects.has(family_id), "%s family resolves" % route_id); _expect(not declared.has(family_id), "%s family declared once" % route_id); declared[family_id] = true
			var previous_end: int = -1
			for raw_event: Variant in events:
				var e: Dictionary = _dict(raw_event); var tick: int = int(e.get("tick", -1)); var span: int = int(e.get("duration_ticks", 0)); var family_id: String = String(e.get("family_id", "")); var effect_id: String = String(e.get("effect", ""))
				_expect(tick >= 0 and span > 0 and tick + span <= duration, "%s event in route" % route_id); _expect(declared.has(family_id), "%s event family declared" % route_id); _expect(_array(allowed_effects.get(family_id, [])).has(effect_id), "%s effect grammar" % route_id)
				if tier == "2": _expect(tick >= previous_end, "%s Tier-2 events non-overlap" % route_id)
				previous_end = tick + span
	_expect(seen.size() == 18, "authored routes cover R01-R18")

func _test_campaign_contracts() -> void:
	var docs: Array = [_load_json("res://content/contracts/campaign_chapter1_batch_01.json"), _load_json("res://content/contracts/campaign_chapter2_batch_01.json"), _load_json("res://content/contracts/campaign_chapter3_batch_01.json")]
	var hold_ids: Dictionary = {}; var route_defs: Dictionary = {}; var species_ids: Dictionary = {}; var support_ids: Dictionary = {}
	for path: String in ["res://content/holds/launch_hold_geometry_batch_01.json","res://content/holds/launch_hold_geometry_batch_02.json","res://content/holds/launch_hold_geometry_batch_03.json"]:
		for raw: Variant in _array(_dict(_load_json(path).get("payload", {})).get("definitions", [])): hold_ids[String(_dict(raw).get("id", ""))] = true
	for path: String in ["res://content/routes/launch_route_profiles_batch_01.json","res://content/routes/launch_route_profiles_batch_02.json","res://content/routes/launch_route_profiles_batch_03.json"]:
		for raw: Variant in _array(_dict(_load_json(path).get("payload", {})).get("definitions", [])): route_defs[String(_dict(raw).get("id", ""))] = _dict(raw)
	for raw: Variant in _array(_dict(_load_json("res://content/species/launch_roster.json").get("payload", {})).get("definitions", [])): species_ids[String(_dict(raw).get("id", ""))] = true
	for raw: Variant in _array(_dict(_load_json("res://content/supports/launch_supports.json").get("payload", {})).get("definitions", [])): support_ids[String(_dict(raw).get("id", ""))] = true
	var seen: Dictionary = {}; var chapter2_spacing_inferior: int = 0; var chapter2_two_changes: int = 0; var chapter3_spacing_inferior: int = 0; var chapter3_two_changes: int = 0; var chapter3_growth_edge_inferior: int = 0; var chapter3_wake_timing: int = 0; var chapter3_feed_intro: bool = false; var chapter3_nest_intro: bool = false
	for raw_doc: Variant in docs:
		for raw: Variant in _array(_dict(_dict(raw_doc).get("payload", {})).get("definitions", [])):
			var d: Dictionary = _dict(raw); var cid: String = String(d.get("id", "")); _expect(not seen.has(cid), "%s appears once" % cid); seen[cid] = true
			_expect(hold_ids.has(String(d.get("hold_id", ""))), "%s hold resolves" % cid)
			var rid: String = String(d.get("route_id", "")); _expect(route_defs.has(rid), "%s route resolves" % cid)
			for sid: Variant in _array(d.get("species_ids", [])): _expect(species_ids.has(String(sid)), "%s species resolves" % cid)
			for sid: Variant in _array(d.get("support_ids", [])): _expect(support_ids.has(String(sid)), "%s support resolves" % cid)
			if cid in ["C05","C06","C07","C08","C09","C10","C11","C12","C13","C14","C15","C16","C17","C18","C19","C20","C21","C22","C23","C24"]: _expect(bool(d.get("requires_post_launch_change", false)), "%s preserves dynamic transit gate" % cid)
			if cid.begins_with("C1") and cid != "C01":
				if int(cid.trim_prefix("C")) <= 16:
					if bool(d.get("maximum_spacing_inferior", false)): chapter2_spacing_inferior += 1
					if int(d.get("temporally_separated_changes", 0)) >= 2: chapter2_two_changes += 1
					if route_defs.has(rid): _expect(String(_dict(route_defs[rid]).get("tier", "")) == "2", "%s uses Tier-2 route ceiling" % cid)
			if int(cid.trim_prefix("C")) >= 17 and int(cid.trim_prefix("C")) <= 24:
				if bool(d.get("maximum_spacing_inferior", false)): chapter3_spacing_inferior += 1
				if int(d.get("temporally_separated_changes", 0)) >= 2: chapter3_two_changes += 1
				if bool(d.get("growth_reserve_edge_inferior", false)): chapter3_growth_edge_inferior += 1
				if bool(d.get("vibration_wake_timing", false)):
					chapter3_wake_timing += 1
					var route: Dictionary = _dict(route_defs.get(rid, {})); var has_wake: bool = false
					for raw_event: Variant in _array(route.get("events", [])):
						if String(_dict(raw_event).get("effect", "")) == "wake_request": has_wake = true
					_expect(has_wake, "%s wake-timing evidence binds a wake_request route" % cid)
				var route_tier: String = String(_dict(route_defs.get(rid, {})).get("tier", "")); _expect(route_tier in ["2","3"], "%s route complexity is legal for Tier 3" % cid)
				if cid == "C19": chapter3_feed_intro = _array(d.get("support_ids", [])).has("S05")
				if cid == "C20": chapter3_nest_intro = _array(d.get("support_ids", [])).has("S04")
	_expect(seen.size() == 24, "campaign payloads cover C01-C24")
	_expect(chapter2_spacing_inferior >= 2, "Chapter 2 has at least two maximum-spacing-inferior authored cases")
	_expect(chapter2_two_changes >= 4, "Chapter 2 contributes multiple two-change dynamic-transit cases")
	_expect(chapter3_spacing_inferior >= 2, "Chapter 3 has at least two maximum-spacing-inferior authored cases")
	_expect(chapter3_two_changes >= 6, "Chapter 3 is strongly dynamic across separated transit changes")
	_expect(chapter3_growth_edge_inferior >= 1, "Chapter 3 breaks the permanent growth corner/edge reserve template")
	_expect(chapter3_wake_timing >= 1, "Chapter 3 includes vibration wake timing")
	_expect(chapter3_feed_intro, "C19 introduces Feed Cartridge S05")
	_expect(chapter3_nest_intro, "C20 introduces Nest Pad S04")

func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: _expect(false, "open %s" % path); return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text()); _expect(parsed is Dictionary, "parse %s" % path); return _dict(parsed)
func _array(value: Variant) -> Array: return value if value is Array else []
func _dict(value: Variant) -> Dictionary: return value if value is Dictionary else {}
func _cell_key(cell: Array) -> String: return "invalid" if cell.size() != 2 else "%d,%d" % [int(cell[0]), int(cell[1])]
func _in_bounds(cell: Array, width: int, height: int) -> bool: return cell.size() == 2 and int(cell[0]) >= 0 and int(cell[0]) < width and int(cell[1]) >= 0 and int(cell[1]) < height
func _expect(value: bool, label: String) -> void:
	if not value: failures += 1; push_error("FAIL: %s" % label)
