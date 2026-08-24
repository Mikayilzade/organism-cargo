extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_hold_geometry()
	_test_route_profiles()
	_test_chapter1_contracts()
	if failures == 0:
		print("launch_authored_batch_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_authored_batch_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_hold_geometry() -> void:
	var docs: Array = [_load_json("res://content/holds/launch_hold_geometry_batch_01.json"), _load_json("res://content/holds/launch_hold_geometry_batch_02.json")]
	var limits: Dictionary = {
		"H01":[5,6,5,5,1,2],"H02":[5,6,5,5,1,2],"H03":[5,6,5,5,1,2],
		"H04":[5,6,6,6,2,2],"H05":[5,6,6,6,2,2],"H06":[5,6,6,6,2,2],
		"H07":[5,9,5,7,2,3],"H08":[5,9,5,7,2,3]
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
	_expect(seen.size() == 8, "authored geometry now covers H01-H08")

func _test_route_profiles() -> void:
	var docs: Array = [_load_json("res://content/routes/launch_route_profiles_batch_01.json"), _load_json("res://content/routes/launch_route_profiles_batch_02.json")]
	var allowed_effects: Dictionary = {"RH1":["heat_input"],"RH2":["contamination_source"],"RH3":["stress_field","wake_request"]}
	var seen: Dictionary = {}
	for raw_doc: Variant in docs:
		for raw_definition: Variant in _array(_dict(_dict(raw_doc).get("payload", {})).get("definitions", [])):
			var d: Dictionary = _dict(raw_definition); var route_id: String = String(d.get("id", "")); var tier: String = String(d.get("tier", "")); var duration: int = int(d.get("duration_ticks", 0)); var families: Array = _array(d.get("hazard_family_ids", [])); var events: Array = _array(d.get("events", []))
			_expect(not seen.has(route_id), "%s appears once" % route_id); seen[route_id] = true; _expect(duration > 0 and duration <= 24, "%s duration <=24" % route_id)
			var max_families: int = 2
			if tier == "0-1" or tier == "2": max_families = 1
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
	_expect(seen.size() == 12, "authored routes now cover R01-R12")

func _test_chapter1_contracts() -> void:
	var doc: Dictionary = _load_json("res://content/contracts/campaign_chapter1_batch_01.json")
	var defs: Array = _array(_dict(doc.get("payload", {})).get("definitions", [])); _expect(defs.size() == 8, "chapter 1 has C01-C08 payloads")
	var hold_ids: Dictionary = {}; var route_ids: Dictionary = {}; var species_ids: Dictionary = {}; var support_ids: Dictionary = {}
	for path: String in ["res://content/holds/launch_hold_geometry_batch_01.json","res://content/holds/launch_hold_geometry_batch_02.json"]:
		for raw: Variant in _array(_dict(_load_json(path).get("payload", {})).get("definitions", [])): hold_ids[String(_dict(raw).get("id", ""))] = true
	for path: String in ["res://content/routes/launch_route_profiles_batch_01.json","res://content/routes/launch_route_profiles_batch_02.json"]:
		for raw: Variant in _array(_dict(_load_json(path).get("payload", {})).get("definitions", [])): route_ids[String(_dict(raw).get("id", ""))] = true
	for raw: Variant in _array(_dict(_load_json("res://content/species/launch_roster.json").get("payload", {})).get("definitions", [])): species_ids[String(_dict(raw).get("id", ""))] = true
	for raw: Variant in _array(_dict(_load_json("res://content/supports/launch_supports.json").get("payload", {})).get("definitions", [])): support_ids[String(_dict(raw).get("id", ""))] = true
	var seen: Dictionary = {}
	for raw: Variant in defs:
		var d: Dictionary = _dict(raw); var cid: String = String(d.get("id", "")); _expect(not seen.has(cid), "%s appears once" % cid); seen[cid] = true
		_expect(hold_ids.has(String(d.get("hold_id", ""))), "%s hold resolves" % cid); _expect(route_ids.has(String(d.get("route_id", ""))), "%s route resolves" % cid)
		for sid: Variant in _array(d.get("species_ids", [])): _expect(species_ids.has(String(sid)), "%s species resolves" % cid)
		for sid: Variant in _array(d.get("support_ids", [])): _expect(support_ids.has(String(sid)), "%s support resolves" % cid)
		if cid in ["C05","C06","C07","C08"]: _expect(bool(d.get("requires_post_launch_change", false)), "%s preserves dynamic transit gate" % cid)

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
